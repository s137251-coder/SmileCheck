import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import 'home_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final isClean = result.score >= 80;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: isClean ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  isClean ? Icons.check : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 58,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isClean ? 'Looks clean' : 'Check needed',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${result.score.toStringAsFixed(1)} / 100',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isClean ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                result.notes,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
