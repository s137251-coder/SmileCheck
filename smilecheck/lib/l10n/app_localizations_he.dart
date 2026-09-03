// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class LHe extends L {
  LHe([String locale = 'he']) : super(locale);

  @override
  String get languageName => 'עברית';

  @override
  String get languageTitle => 'שפה';

  @override
  String get languageTooltip => 'שפה';

  @override
  String get tagline => 'בדיקת חיוך פרטית לפני שיוצאים';

  @override
  String get privacyOnDevice => 'הכול רץ על המכשיר הזה';

  @override
  String get privacyNoUploads => 'אין העלאות. שום דבר לא נשמר.';

  @override
  String get privacyNeverLeft => 'התמונה הזו לא יצאה מהמכשיר';

  @override
  String get onDeviceOnly => 'עיבוד מקומי בלבד';

  @override
  String get hintFrameUp => 'יישרו את החיוך בתוך המסגרת';

  @override
  String get hintHoldStill => 'החזיקו יציב...';

  @override
  String get hintCameraPending => 'מכינים את המצלמה';

  @override
  String get hintCameraUnavailable => 'המצלמה לא זמינה';

  @override
  String get preparingCamera => 'מכינים את המצלמה...';

  @override
  String get startCheck => 'התחלת בדיקת חיוך';

  @override
  String get flashTooltip => 'פלאש';

  @override
  String get switchCameraTooltip => 'החלפת מצלמה';

  @override
  String get cameraAccessNeeded => 'נדרשת גישה למצלמה';

  @override
  String get cameraUnavailable => 'המצלמה לא זמינה';

  @override
  String get openSettings => 'פתיחת הגדרות';

  @override
  String get allowCamera => 'אישור גישה למצלמה';

  @override
  String get tryAgain => 'לנסות שוב';

  @override
  String get cameraBlocked =>
      'הגישה למצלמה חסומה עבור SmileCheck. יש להפעיל אותה בהגדרות המערכת כדי להריץ בדיקה.';

  @override
  String get cameraDenied =>
      'SmileCheck צריכה את המצלמה כדי להסתכל על החיוך. שום דבר לא יוצא מהמכשיר.';

  @override
  String get cameraNoneFound => 'לא נמצאה מצלמה במכשיר הזה.';

  @override
  String cameraListFailed(String detail) {
    return 'לא ניתן לקרוא את רשימת המצלמות: $detail';
  }

  @override
  String cameraStartFailed(String detail) {
    return 'לא ניתן להפעיל את המצלמה: $detail';
  }

  @override
  String cameraCaptureFailed(String detail) {
    return 'הצילום נכשל: $detail';
  }

  @override
  String get cameraNoFlash => 'למצלמה הזו אין פלאש הניתן לשליטה.';

  @override
  String get processingTitle => 'מעבדים את החיוך';

  @override
  String get processingStepRead => 'קוראים את התמונה שצולמה';

  @override
  String get processingStepMeasure => 'מודדים חשיפה ומיקוד';

  @override
  String get processingStepCheck => 'בודקים את החיוך';

  @override
  String get badgeModelVerdict => 'פסק דין ממודל מקומי';

  @override
  String get badgeDemoMode => 'מצב הדגמה - אין מודל מאומן';

  @override
  String get badgeAnalysisError => 'שגיאת ניתוח';

  @override
  String get captionCleanliness => 'ניקיון';

  @override
  String get captionCaptureQuality => 'איכות צילום';

  @override
  String get captionNoReading => 'אין מדידה';

  @override
  String get headlineLooksClean => 'נראה נקי';

  @override
  String get headlineCheckNeeded => 'כדאי לבדוק';

  @override
  String get headlineNoVerdict => 'אין עדיין פסק דין';

  @override
  String get headlineFailed => 'הניתוח נכשל';

  @override
  String get labelNoParticles => 'לא זוהו שאריות מזון';

  @override
  String get labelParticlesFound => 'זוהו שאריות מזון';

  @override
  String get labelCaptureOnly => 'איכות צילום בלבד';

  @override
  String get labelNothingMeasured => 'לא נמדד דבר';

  @override
  String get notesClean => 'המודל המקומי לא מצא שאריות סביב החיוך.';

  @override
  String get notesNeedsCheck =>
      'המודל המקומי סימן שאריות אפשריות. שווה שטיפה מהירה.';

  @override
  String get reasonNoFrame =>
      'לא צולמה תמונה, ולכן לא היה מה לנתח. בדקו את הגישה למצלמה ונסו שוב.';

  @override
  String get reasonModelMissing =>
      'לא מצורף מודל. הוסיפו מודל בינארי נקי/מלוכלך כדי לקבל פסק דין אמיתי.';

  @override
  String reasonModelWrongOutputs(int classes) {
    return 'המודל המצורף מחזיר $classes מחלקות, ולכן הוא מסווג כללי ולא מסווג ניקיון חיוך. SmileCheck צריכה בדיוק 2 מוצאים, [נקי, מלוכלך], ולכן מדווחת רק איכות הצילום.';
  }

  @override
  String reasonModelWrongRank(int rank) {
    return 'המודל המצורף מצפה לקלט בדרגה $rank. SmileCheck צריכה [1, גובה, רוחב, ערוצים].';
  }

  @override
  String reasonModelWrongChannels(int channels) {
    return 'המודל המצורף מצפה ל-$channels ערוצי קלט. SmileCheck תומכת ב-1 או 3.';
  }

  @override
  String reasonModelWrongInputType(String type) {
    return 'המודל המצורף מקבל קלט מסוג $type. SmileCheck מספקת float32 או uint8.';
  }

  @override
  String reasonModelOpenFailed(String detail) {
    return 'לא ניתן לפתוח את המודל המצורף: $detail';
  }

  @override
  String reasonModelRunFailed(String detail) {
    return 'המודל המקומי נכשל במהלך ההרצה והוסר מהזיכרון: $detail';
  }

  @override
  String reasonDecodeFailed(String detail) {
    return 'לא ניתן לקרוא את התמונה שצולמה: $detail';
  }

  @override
  String get reasonTimedOut =>
      'לא הספקנו לעבד את התמונה בזמן. נסו שוב בתאורה טובה יותר.';

  @override
  String get hintTooDark => 'התמונה כהה. התקרבו לאור.';

  @override
  String get hintTooBright => 'התמונה שרופה. צאו מאור ישיר.';

  @override
  String get hintTooSoft => 'התמונה מטושטשת. החזיקו יציב וצלמו שוב.';

  @override
  String get hintTooFlat => 'התמונה שטוחה. התקרבו קצת לחיוך.';

  @override
  String get measurementsTitle => 'מדידות התמונה';

  @override
  String get measurementsSubtitle => 'נמדדו מקומית מהצילום הזה';

  @override
  String get metricBrightness => 'בהירות';

  @override
  String get metricContrast => 'ניגודיות';

  @override
  String get metricSharpness => 'חדות';

  @override
  String get checkAgain => 'בדיקה נוספת';
}
