import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:smilecheck/core/guide_geometry.dart';

void main() {
  const frame = Size(1080, 1920);

  group('GuideGeometry', () {
    test('the mouth hint sits inside the aiming window', () {
      final window = GuideGeometry.window(frame);
      final hint = GuideGeometry.mouthHint(window);

      expect(window.contains(hint.topLeft), isTrue);
      expect(window.contains(hint.bottomRight), isTrue);
    });

    test('the fallback crop stays inside the frame', () {
      final crop = GuideGeometry.fallbackCrop(frame);

      expect(crop.left, greaterThanOrEqualTo(0));
      expect(crop.top, greaterThanOrEqualTo(0));
      expect(crop.right, lessThanOrEqualTo(frame.width));
      expect(crop.bottom, lessThanOrEqualTo(frame.height));
    });

    test('the fallback crop is centred on the drawn mouth hint', () {
      final hint = GuideGeometry.mouthHint(GuideGeometry.window(frame));
      final crop = GuideGeometry.fallbackCrop(frame);

      // The user aims at the hint, so a frame with no detectable face must be
      // analysed there and nowhere else.
      expect(crop.center.dx, closeTo(hint.center.dx, 1));
      expect(crop.center.dy, closeTo(hint.center.dy, 1));
    });

    test('the crop is far smaller than the frame it came from', () {
      final crop = GuideGeometry.fallbackCrop(frame);
      final share = (crop.width * crop.height) / (frame.width * frame.height);

      // The whole point: spend the model's 224 pixels on the mouth rather
      // than on cheeks and background.
      expect(share, lessThan(0.15));
    });

    test('crop padding matches the training pipeline', () {
      // crop_mouth.py defaults to --pad 2.1 and a 0.62 aspect. If either side
      // changes alone, the model sees a framing it was not trained on.
      expect(GuideGeometry.mouthCropPad, 2.1);
      expect(GuideGeometry.mouthCropAspect, 0.62);
    });
  });
}
