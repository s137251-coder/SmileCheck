import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/analysis_result.dart';
import '../services/analysis_service.dart';
import '../widgets/scan_overlay.dart';
import 'result_screen.dart';

/// Shows the frozen frame being scanned while the local analysis runs.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  /// Keeps the scan visible long enough to read even when analysis is instant.
  static const Duration _minimumVisible = Duration(milliseconds: 700);

  static const int _stepCount = 3;

  Timer? _stepTimer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(
      const Duration(milliseconds: 480),
      (_) {
        if (!mounted) return;
        setState(() => _step = (_step + 1) % _stepCount);
      },
    );
    unawaited(_run());
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    final service = context.read<AnalysisService>();
    AnalysisResult result;

    try {
      final results = await Future.wait<Object?>([
        service
            .analyzeImage(imagePath: widget.imagePath)
            .timeout(const Duration(seconds: 20)),
        Future<void>.delayed(_minimumVisible),
      ]);
      result = results.first! as AnalysisResult;
    } on TimeoutException {
      result = AnalysisResult.failure(ResultReason.timedOut);
    } on Object catch (error) {
      result = AnalysisResult.failure(
        ResultReason.decodeFailed,
        detail: '$error',
      );
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => ResultScreen(result: result),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String _stepLabel(L l) {
    switch (_step) {
      case 0:
        return l.processingStepRead;
      case 1:
        return l.processingStepMeasure;
      default:
        return l.processingStepCheck;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath;
    final l = L.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backdrop),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.gutter),
            child: Column(
              children: [
                const Spacer(),
                Expanded(
                  flex: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (path != null)
                          Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.surface,
                            ),
                          )
                        else
                          const ColoredBox(color: AppColors.surface),
                        const ScanOverlay(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  l.processingTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Row(
                    key: ValueKey<int>(_step),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 11),
                      Text(
                        _stepLabel(l),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
