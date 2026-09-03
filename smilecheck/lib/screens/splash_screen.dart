import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/ui_bits.dart';
import 'home_screen.dart';

/// Brand moment on cold start. Short by design: the spec budgets one to two
/// seconds before the camera appears.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _hold = Duration(milliseconds: 1500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _hold,
  )..forward();

  late final Animation<double> _markScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
  );

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onDone);
  }

  void _onDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onDone)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backdrop),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.gutter),
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1).animate(_markScale),
                  child: FadeTransition(
                    opacity: _markScale,
                    child: const BrandMark(size: 108),
                  ),
                ),
                const SizedBox(height: 30),
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Text(
                        'SmileCheck',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(letterSpacing: -1),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'A private smile check before you walk out',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _textFade,
                  child: const InfoPill(
                    icon: Icons.lock_outline_rounded,
                    label: 'Runs entirely on this device',
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: AppMetrics.pill,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _controller.value,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceRaised,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
