import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/camera_service.dart';
import 'processing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CameraService _cameraService;

  bool _isLoading = true;
  bool _isAnalyzing = false;
  String _status = 'Preparing camera and permissions...';

  @override
  void initState() {
    super.initState();
    _cameraService = context.read<CameraService>();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = 'Camera ready';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = error.toString();
      });
    }
  }

  Future<void> _runLocalCheck() async {
    setState(() {
      _isAnalyzing = true;
      _status = 'Running local smile analysis...';
    });

    try {
      if (!mounted) return;

      final imagePath = await _cameraService.captureImage();
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingScreen(imagePath: imagePath),
        ),
      );
    } catch (error) {
      setState(() {
        _status = 'Analysis failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _cameraService.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmileCheck'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmileCheck',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quick, private, and local smile check before you go out.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Preparing camera...'),
                          ],
                        ),
                      )
                    : preview != null && preview.value.isInitialized
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: CameraPreview(preview),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _status,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isAnalyzing ? null : _runLocalCheck,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Start smile check'),
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
