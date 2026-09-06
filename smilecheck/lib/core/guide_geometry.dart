import 'dart:ui';

/// Where the aiming frame sits, as fractions of the frame it is drawn over.
///
/// Both the overlay the user lines themselves up with and the fallback crop
/// used when no face is found read these numbers. Keeping one copy is the
/// point: if the drawn guide and the cropped region drifted apart, the app
/// would be telling the user to aim at one place and analysing another.
class GuideGeometry {
  const GuideGeometry._();

  /// Aiming window, as a fraction of the frame width, and its height relative
  /// to its own width.
  static const double windowWidthFactor = 0.78;
  static const double windowAspect = 1.22;

  /// Vertical centre of the window, as a fraction of frame height.
  static const double windowCentreY = 0.46;

  /// The mouth hint sits below the window centre by this fraction of the
  /// window height, and spans this fraction of the window width.
  static const double mouthOffsetY = 0.16;
  static const double mouthWidthFactor = 0.5;
  static const double mouthHeightFactor = 0.22;

  static Rect window(Size size) {
    final width = size.width * windowWidthFactor;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * windowCentreY),
      width: width,
      height: width * windowAspect,
    );
  }

  static Rect mouthHint(Rect window) {
    return Rect.fromCenter(
      center: Offset(
        window.center.dx,
        window.center.dy + window.height * mouthOffsetY,
      ),
      width: window.width * mouthWidthFactor,
      height: window.height * mouthHeightFactor,
    );
  }

  /// The region to analyse when no face could be located.
  ///
  /// Sized like the landmark-driven crop — a little over twice the expected
  /// mouth width — so a fallback frame and a detected one reach the model at
  /// comparable scale.
  static Rect fallbackCrop(Size size) {
    final hint = mouthHint(window(size));
    final width = hint.width * 1.4;
    return Rect.fromCenter(
      center: hint.center,
      width: width,
      height: width * mouthCropAspect,
    ).intersect(Offset.zero & size);
  }

  /// Height of the analysed crop relative to its width.
  static const double mouthCropAspect = 0.62;

  /// Crop width as a multiple of the measured mouth width. Matches `--pad` in
  /// the training pipeline's `crop_mouth.py`; the two must stay equal or the
  /// model sees a different framing than it was trained on.
  static const double mouthCropPad = 2.1;
}
