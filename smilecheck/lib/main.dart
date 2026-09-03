import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/analysis_service.dart';
import 'services/camera_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is camera-first and dark throughout, so the status bar icons are
  // pinned light rather than following the system theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070C16),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    MultiProvider(
      providers: [
        // Both services outlive every screen: the camera keeps its controller
        // across navigation, and the interpreter is loaded only once.
        ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
        Provider<AnalysisService>(
          create: (_) => AnalysisService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: const SmileCheckApp(),
    ),
  );
}
