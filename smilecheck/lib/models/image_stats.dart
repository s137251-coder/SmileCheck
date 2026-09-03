/// The single most useful thing to tell the user about their capture.
///
/// A code rather than a sentence: the wording belongs to the UI, which knows
/// the active language.
enum CaptureHint { tooDark, tooBright, tooSoft, tooFlat }

/// Objective measurements taken from the captured frame.
///
/// These describe the *photo*, not the teeth. They are what a local pass over
/// the pixels can honestly report, and they drive the capture-quality score
/// shown when no trained model is available.
class ImageStats {
  const ImageStats({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  /// Mean luma, 0..1.
  final double brightness;

  /// Standard deviation of luma, 0..1. Low values mean a flat, washed frame.
  final double contrast;

  /// Mean absolute neighbour difference, 0..1. Low values mean a soft or
  /// blurred frame, the usual reason a smile check would be unreliable.
  final double sharpness;

  static const ImageStats zero =
      ImageStats(brightness: 0, contrast: 0, sharpness: 0);

  bool get isEmpty => brightness == 0 && contrast == 0 && sharpness == 0;

  /// How usable the capture is, 0..100.
  ///
  /// Brightness scores as distance from a well-exposed 0.55 mid-point, so both
  /// a dark frame and a blown-out frame lose points. Contrast and sharpness are
  /// scored against the level a phone selfie normally reaches.
  double get captureQuality {
    if (isEmpty) return 0;

    final exposure = (1.0 - ((brightness - 0.55).abs() / 0.55)).clamp(0.0, 1.0);
    final detail = (contrast / 0.22).clamp(0.0, 1.0);
    final focus = (sharpness / 0.12).clamp(0.0, 1.0);

    return (((exposure * 0.45) + (detail * 0.25) + (focus * 0.30)) * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  /// The single biggest thing wrong with the capture, or null when it is fine.
  CaptureHint? get primaryHint {
    if (isEmpty) return null;
    if (brightness < 0.28) return CaptureHint.tooDark;
    if (brightness > 0.82) return CaptureHint.tooBright;
    if (sharpness < 0.05) return CaptureHint.tooSoft;
    if (contrast < 0.10) return CaptureHint.tooFlat;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'sharpness': sharpness,
        'captureQuality': captureQuality,
      };
}
