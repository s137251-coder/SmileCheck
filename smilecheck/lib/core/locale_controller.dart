import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the interface language and remembers the user's choice.
///
/// The stored value is a two-letter tag and nothing else — a UI preference, not
/// personal data, and it never leaves the device.
class LocaleController extends ChangeNotifier {
  LocaleController({Locale? initial})
      : _locale = initial ?? _deviceDefault();

  static const String _storageKey = 'smilecheck.locale';

  static const List<Locale> supported = <Locale>[Locale('en'), Locale('he')];

  Locale _locale;
  Locale get locale => _locale;

  /// Restores the saved choice. Falls back to the device language when the user
  /// has not chosen yet, and to English when the device speaks neither.
  static Future<LocaleController> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null && _isSupported(saved)) {
        return LocaleController(initial: Locale(saved));
      }
    } on Object {
      // A preferences backend that will not open is not worth blocking start-up
      // over; the device default is a reasonable answer.
    }
    return LocaleController();
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode) || locale == _locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, locale.languageCode);
    } on Object {
      // The choice still applies for this session even if it cannot be saved.
    }
  }

  static bool _isSupported(String code) =>
      supported.any((locale) => locale.languageCode == code);

  static Locale _deviceDefault() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return _isSupported(code) ? Locale(code) : const Locale('en');
  }
}
