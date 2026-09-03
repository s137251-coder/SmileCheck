// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageTooltip => 'Language';

  @override
  String get tagline => 'A private smile check before you walk out';

  @override
  String get privacyOnDevice => 'Runs entirely on this device';

  @override
  String get privacyNoUploads => 'No uploads. Nothing is stored.';

  @override
  String get privacyNeverLeft => 'This photo never left your device';

  @override
  String get onDeviceOnly => 'On-device only';

  @override
  String get hintFrameUp => 'Line your smile up inside the frame';

  @override
  String get hintHoldStill => 'Hold still...';

  @override
  String get hintCameraPending => 'Getting the camera ready';

  @override
  String get hintCameraUnavailable => 'Camera unavailable';

  @override
  String get preparingCamera => 'Preparing camera...';

  @override
  String get startCheck => 'Start smile check';

  @override
  String get flashTooltip => 'Flash';

  @override
  String get switchCameraTooltip => 'Switch camera';

  @override
  String get cameraAccessNeeded => 'Camera access needed';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get openSettings => 'Open settings';

  @override
  String get allowCamera => 'Allow camera';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cameraBlocked =>
      'Camera access is blocked for SmileCheck. Enable it in system settings to run a check.';

  @override
  String get cameraDenied =>
      'SmileCheck needs the camera to look at your smile. Nothing leaves your device.';

  @override
  String get cameraNoneFound => 'No camera was found on this device.';

  @override
  String cameraListFailed(String detail) {
    return 'The camera list could not be read: $detail';
  }

  @override
  String cameraStartFailed(String detail) {
    return 'The camera could not be started: $detail';
  }

  @override
  String cameraCaptureFailed(String detail) {
    return 'The capture failed: $detail';
  }

  @override
  String get cameraNoFlash => 'This camera has no controllable flash.';

  @override
  String get processingTitle => 'Processing your smile';

  @override
  String get processingStepRead => 'Reading the captured frame';

  @override
  String get processingStepMeasure => 'Measuring exposure and focus';

  @override
  String get processingStepCheck => 'Checking your smile';

  @override
  String get badgeModelVerdict => 'On-device model verdict';

  @override
  String get badgeDemoMode => 'Demo mode - no trained model';

  @override
  String get badgeAnalysisError => 'Analysis error';

  @override
  String get captionCleanliness => 'CLEANLINESS';

  @override
  String get captionCaptureQuality => 'CAPTURE QUALITY';

  @override
  String get captionNoReading => 'NO READING';

  @override
  String get headlineLooksClean => 'Looks clean';

  @override
  String get headlineCheckNeeded => 'Check needed';

  @override
  String get headlineNoVerdict => 'No verdict yet';

  @override
  String get headlineFailed => 'Analysis failed';

  @override
  String get labelNoParticles => 'No food particles detected';

  @override
  String get labelParticlesFound => 'Food particles detected';

  @override
  String get labelCaptureOnly => 'Capture quality only';

  @override
  String get labelNothingMeasured => 'Nothing was measured';

  @override
  String get notesClean =>
      'The on-device model found no residue around your smile.';

  @override
  String get notesNeedsCheck =>
      'The on-device model flagged possible residue. Worth a quick rinse.';

  @override
  String get reasonNoFrame =>
      'No frame was captured, so there was nothing to analyse. Check camera access and try again.';

  @override
  String get reasonModelMissing =>
      'No model is bundled. Add a binary clean/dirty model to enable real verdicts.';

  @override
  String reasonModelWrongOutputs(int classes) {
    return 'The bundled model returns $classes classes, so it is a general-purpose classifier rather than a smile-cleanliness one. SmileCheck needs exactly 2 outputs, [clean, dirty], so only capture quality is reported.';
  }

  @override
  String reasonModelWrongRank(int rank) {
    return 'The bundled model expects a rank-$rank input. SmileCheck needs [1, height, width, channels].';
  }

  @override
  String reasonModelWrongChannels(int channels) {
    return 'The bundled model expects $channels input channels. SmileCheck supports 1 or 3.';
  }

  @override
  String reasonModelWrongInputType(String type) {
    return 'The bundled model takes $type input. SmileCheck supplies float32 or uint8.';
  }

  @override
  String reasonModelOpenFailed(String detail) {
    return 'The bundled model could not be opened: $detail';
  }

  @override
  String reasonModelRunFailed(String detail) {
    return 'The local model failed during inference and was unloaded: $detail';
  }

  @override
  String reasonDecodeFailed(String detail) {
    return 'The captured frame could not be read: $detail';
  }

  @override
  String get reasonTimedOut =>
      'The frame could not be processed in time. Try again in better light.';

  @override
  String get hintTooDark => 'The frame is dark. Move towards more light.';

  @override
  String get hintTooBright =>
      'The frame is over-exposed. Step out of direct light.';

  @override
  String get hintTooSoft => 'The frame looks soft. Hold steady and retake.';

  @override
  String get hintTooFlat =>
      'The frame is flat. Get a little closer to your smile.';

  @override
  String get measurementsTitle => 'Frame measurements';

  @override
  String get measurementsSubtitle => 'Taken locally from this capture';

  @override
  String get metricBrightness => 'Brightness';

  @override
  String get metricContrast => 'Contrast';

  @override
  String get metricSharpness => 'Sharpness';

  @override
  String get checkAgain => 'Check again';
}
