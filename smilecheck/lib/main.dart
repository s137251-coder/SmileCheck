import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:smilecheck/app.dart';
import 'package:smilecheck/services/analysis_service.dart';
import 'package:smilecheck/services/camera_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<CameraService>(create: (_) => CameraService()),
        Provider<AnalysisService>(
          create: (_) => AnalysisService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: const SmileCheckApp(),
    ),
  );
}
