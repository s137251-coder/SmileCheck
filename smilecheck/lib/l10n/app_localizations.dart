import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTooltip;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'A private smile check before you walk out'**
  String get tagline;

  /// No description provided for @privacyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Runs entirely on this device'**
  String get privacyOnDevice;

  /// No description provided for @privacyNoUploads.
  ///
  /// In en, this message translates to:
  /// **'No uploads. Nothing is stored.'**
  String get privacyNoUploads;

  /// No description provided for @privacyNeverLeft.
  ///
  /// In en, this message translates to:
  /// **'This photo never left your device'**
  String get privacyNeverLeft;

  /// No description provided for @onDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On-device only'**
  String get onDeviceOnly;

  /// No description provided for @hintFrameUp.
  ///
  /// In en, this message translates to:
  /// **'Line your smile up inside the frame'**
  String get hintFrameUp;

  /// No description provided for @hintHoldStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still...'**
  String get hintHoldStill;

  /// No description provided for @hintCameraPending.
  ///
  /// In en, this message translates to:
  /// **'Getting the camera ready'**
  String get hintCameraPending;

  /// No description provided for @hintCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get hintCameraUnavailable;

  /// No description provided for @preparingCamera.
  ///
  /// In en, this message translates to:
  /// **'Preparing camera...'**
  String get preparingCamera;

  /// No description provided for @startCheck.
  ///
  /// In en, this message translates to:
  /// **'Start smile check'**
  String get startCheck;

  /// No description provided for @flashTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get flashTooltip;

  /// No description provided for @switchCameraTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCameraTooltip;

  /// No description provided for @cameraAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get cameraAccessNeeded;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailable;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @allowCamera.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get allowCamera;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cameraBlocked.
  ///
  /// In en, this message translates to:
  /// **'Camera access is blocked for SmileCheck. Enable it in system settings to run a check.'**
  String get cameraBlocked;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'SmileCheck needs the camera to look at your smile. Nothing leaves your device.'**
  String get cameraDenied;

  /// No description provided for @cameraNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No camera was found on this device.'**
  String get cameraNoneFound;

  /// No description provided for @cameraListFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera list could not be read: {detail}'**
  String cameraListFailed(String detail);

  /// No description provided for @cameraStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started: {detail}'**
  String cameraStartFailed(String detail);

  /// No description provided for @cameraCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'The capture failed: {detail}'**
  String cameraCaptureFailed(String detail);

  /// No description provided for @cameraNoFlash.
  ///
  /// In en, this message translates to:
  /// **'This camera has no controllable flash.'**
  String get cameraNoFlash;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing your smile'**
  String get processingTitle;

  /// No description provided for @processingStepRead.
  ///
  /// In en, this message translates to:
  /// **'Reading the captured frame'**
  String get processingStepRead;

  /// No description provided for @processingStepMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measuring exposure and focus'**
  String get processingStepMeasure;

  /// No description provided for @processingStepCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking your smile'**
  String get processingStepCheck;

  /// No description provided for @badgeModelVerdict.
  ///
  /// In en, this message translates to:
  /// **'On-device model verdict'**
  String get badgeModelVerdict;

  /// No description provided for @badgeDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode - no trained model'**
  String get badgeDemoMode;

  /// No description provided for @badgeAnalysisError.
  ///
  /// In en, this message translates to:
  /// **'Analysis error'**
  String get badgeAnalysisError;

  /// No description provided for @captionCleanliness.
  ///
  /// In en, this message translates to:
  /// **'CLEANLINESS'**
  String get captionCleanliness;

  /// No description provided for @captionCaptureQuality.
  ///
  /// In en, this message translates to:
  /// **'CAPTURE QUALITY'**
  String get captionCaptureQuality;

  /// No description provided for @captionNoReading.
  ///
  /// In en, this message translates to:
  /// **'NO READING'**
  String get captionNoReading;

  /// No description provided for @headlineLooksClean.
  ///
  /// In en, this message translates to:
  /// **'Looks clean'**
  String get headlineLooksClean;

  /// No description provided for @headlineCheckNeeded.
  ///
  /// In en, this message translates to:
  /// **'Check needed'**
  String get headlineCheckNeeded;

  /// No description provided for @headlineNoVerdict.
  ///
  /// In en, this message translates to:
  /// **'No verdict yet'**
  String get headlineNoVerdict;

  /// No description provided for @headlineFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get headlineFailed;

  /// No description provided for @labelNoParticles.
  ///
  /// In en, this message translates to:
  /// **'No food particles detected'**
  String get labelNoParticles;

  /// No description provided for @labelParticlesFound.
  ///
  /// In en, this message translates to:
  /// **'Food particles detected'**
  String get labelParticlesFound;

  /// No description provided for @labelCaptureOnly.
  ///
  /// In en, this message translates to:
  /// **'Capture quality only'**
  String get labelCaptureOnly;

  /// No description provided for @labelNothingMeasured.
  ///
  /// In en, this message translates to:
  /// **'Nothing was measured'**
  String get labelNothingMeasured;

  /// No description provided for @notesClean.
  ///
  /// In en, this message translates to:
  /// **'The on-device model found no residue around your smile.'**
  String get notesClean;

  /// No description provided for @notesNeedsCheck.
  ///
  /// In en, this message translates to:
  /// **'The on-device model flagged possible residue. Worth a quick rinse.'**
  String get notesNeedsCheck;

  /// No description provided for @reasonNoFrame.
  ///
  /// In en, this message translates to:
  /// **'No frame was captured, so there was nothing to analyse. Check camera access and try again.'**
  String get reasonNoFrame;

  /// No description provided for @reasonModelMissing.
  ///
  /// In en, this message translates to:
  /// **'No model is bundled. Add a binary clean/dirty model to enable real verdicts.'**
  String get reasonModelMissing;

  /// No description provided for @reasonModelWrongOutputs.
  ///
  /// In en, this message translates to:
  /// **'The bundled model returns {classes} classes, so it is a general-purpose classifier rather than a smile-cleanliness one. SmileCheck needs exactly 2 outputs, [clean, dirty], so only capture quality is reported.'**
  String reasonModelWrongOutputs(int classes);

  /// No description provided for @reasonModelWrongRank.
  ///
  /// In en, this message translates to:
  /// **'The bundled model expects a rank-{rank} input. SmileCheck needs [1, height, width, channels].'**
  String reasonModelWrongRank(int rank);

  /// No description provided for @reasonModelWrongChannels.
  ///
  /// In en, this message translates to:
  /// **'The bundled model expects {channels} input channels. SmileCheck supports 1 or 3.'**
  String reasonModelWrongChannels(int channels);

  /// No description provided for @reasonModelWrongInputType.
  ///
  /// In en, this message translates to:
  /// **'The bundled model takes {type} input. SmileCheck supplies float32 or uint8.'**
  String reasonModelWrongInputType(String type);

  /// No description provided for @reasonModelOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The bundled model could not be opened: {detail}'**
  String reasonModelOpenFailed(String detail);

  /// No description provided for @reasonModelRunFailed.
  ///
  /// In en, this message translates to:
  /// **'The local model failed during inference and was unloaded: {detail}'**
  String reasonModelRunFailed(String detail);

  /// No description provided for @reasonDecodeFailed.
  ///
  /// In en, this message translates to:
  /// **'The captured frame could not be read: {detail}'**
  String reasonDecodeFailed(String detail);

  /// No description provided for @reasonTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The frame could not be processed in time. Try again in better light.'**
  String get reasonTimedOut;

  /// No description provided for @hintTooDark.
  ///
  /// In en, this message translates to:
  /// **'The frame is dark. Move towards more light.'**
  String get hintTooDark;

  /// No description provided for @hintTooBright.
  ///
  /// In en, this message translates to:
  /// **'The frame is over-exposed. Step out of direct light.'**
  String get hintTooBright;

  /// No description provided for @hintTooSoft.
  ///
  /// In en, this message translates to:
  /// **'The frame looks soft. Hold steady and retake.'**
  String get hintTooSoft;

  /// No description provided for @hintTooFlat.
  ///
  /// In en, this message translates to:
  /// **'The frame is flat. Get a little closer to your smile.'**
  String get hintTooFlat;

  /// No description provided for @measurementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Frame measurements'**
  String get measurementsTitle;

  /// No description provided for @measurementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Taken locally from this capture'**
  String get measurementsSubtitle;

  /// No description provided for @metricBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get metricBrightness;

  /// No description provided for @metricContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get metricContrast;

  /// No description provided for @metricSharpness.
  ///
  /// In en, this message translates to:
  /// **'Sharpness'**
  String get metricSharpness;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'he':
      return LHe();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
