import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/guide_geometry.dart';

/// The region of a captured frame that actually gets analysed.
class MouthCrop {
  const MouthCrop({required this.rect, required this.fromLandmarks});

  /// In source-image pixels.
  final Rect rect;

  /// False when no face was found and the aiming frame's geometry was used
  /// instead. The result carries this through, because a fallback crop is a
  /// guess about where the user put their mouth.
  final bool fromLandmarks;
}

/// Finds the mouth in a captured frame.
///
/// The app used to hand the model the whole frame resized to 224x224. In an
/// arm's-length selfie that leaves the teeth around 25 pixels tall and a piece
/// of food two or three across, which caps accuracy however good the model is.
/// Cropping to the mouth first is what lifts that ceiling.
///
/// Detection is on-device, like everything else here: nothing about the frame
/// leaves the phone.
class MouthLocator {
  FaceDetector? _detector;

  FaceDetector get _face => _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  /// Returns the crop for [imagePath], falling back to the aiming frame's
  /// geometry when no face is found.
  ///
  /// Never throws: a detector that fails is a reason to analyse the guide
  /// region, not a reason to lose the capture.
  Future<MouthCrop> locate(String imagePath, Size imageSize) async {
    try {
      final faces = await _face.processImage(
        InputImage.fromFilePath(imagePath),
      );
      if (faces.isNotEmpty) {
        final face = faces.reduce(
          (a, b) =>
              a.boundingBox.width * a.boundingBox.height >
                      b.boundingBox.width * b.boundingBox.height
                  ? a
                  : b,
        );
        final rect = _fromLandmarks(face, imageSize);
        if (rect != null) {
          return MouthCrop(rect: rect, fromLandmarks: true);
        }
      }
    } on Object {
      // Fall through: an unavailable or failing detector must not cost the
      // user their capture.
    }

    return MouthCrop(
      rect: GuideGeometry.fallbackCrop(imageSize),
      fromLandmarks: false,
    );
  }

  /// Builds the crop from the mouth-corner landmarks, matching the framing the
  /// training pipeline produces.
  Rect? _fromLandmarks(Face face, Size imageSize) {
    final left = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final right = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (left == null || right == null) return null;

    final centre = Offset(
      (left.x + right.x) / 2,
      (left.y + right.y) / 2,
    );
    final mouthWidth = (left.x - right.x).abs().toDouble();
    if (mouthWidth < 8) return null;

    final width = mouthWidth * GuideGeometry.mouthCropPad;
    final rect = Rect.fromCenter(
      center: centre,
      width: width,
      height: width * GuideGeometry.mouthCropAspect,
    ).intersect(Offset.zero & imageSize);

    if (rect.width < 32 || rect.height < 20) return null;
    return rect;
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
