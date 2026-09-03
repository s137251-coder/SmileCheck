import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis_result.dart';
import '../services/analysis_service.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _runProcessing();
  }

  Future<void> _runProcessing() async {
    final analysisService = context.read<AnalysisService>();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    late final AnalysisResult result;

    try {
      result = await analysisService
          .analyzeImage(imagePath: widget.imagePath)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      result = const AnalysisResult(
        score: 0,
        label: 'Analysis timed out',
        notes: 'The image could not be processed in time. Please try again.',
      );
    } on Object catch (error) {
      result = AnalysisResult(
        score: 0,
        label: 'Analysis failed',
        notes: 'The image could not be analyzed: $error',
      );
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(result: result),
      ),
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
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Processing your smile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Checking for food particles and smile cleanliness.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
