import 'dart:io';

import 'package:image/image.dart' as img;

class ImagePreprocessor {
  Future<List<List<List<double>>>> preprocess(
    String imagePath, {
    int width = 224,
    int height = 224,
    int channels = 3,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _emptyTensor(width: width, height: height, channels: channels);
    }

    final resized = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );

    final tensor = List<List<List<double>>>.generate(
      height,
      (y) => List<List<double>>.generate(
        width,
        (x) {
          final pixel = resized.getPixel(x, y);
          final r = (pixel.r / 255.0).clamp(0.0, 1.0).toDouble();
          final g = (pixel.g / 255.0).clamp(0.0, 1.0).toDouble();
          final b = (pixel.b / 255.0).clamp(0.0, 1.0).toDouble();
          if (channels == 1) {
            final gray = ((r + g + b) / 3.0).clamp(0.0, 1.0).toDouble();
            return [gray];
          }
          return [r, g, b];
        },
      ),
    );

    return tensor;
  }

  Future<double> estimateImageQuality(String? imagePath) async {
    if (imagePath == null) return 0.0;

    final file = File(imagePath);
    if (!await file.exists()) return 0.0;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return 0.0;

    double brightness = 0;
    double contrast = 0;
    int count = 0;

    for (final pixel in decoded) {
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      final lum = ((r * 0.299) + (g * 0.587) + (b * 0.114)) / 255.0;
      brightness += lum;
      contrast += (r - g).abs() + (g - b).abs() + (b - r).abs();
      count++;
    }

    brightness /= count == 0 ? 1 : count;
    contrast /= count == 0 ? 1 : count;

    final quality = ((brightness * 70.0) + ((contrast / 765.0) * 30.0)) * 100.0;
    return quality.clamp(0.0, 100.0).toDouble();
  }

  List<List<List<double>>> _emptyTensor({
    int width = 224,
    int height = 224,
    int channels = 3,
  }) {
    return List<List<List<double>>>.generate(
      height,
      (_) => List<List<double>>.generate(
        width,
        (_) => channels == 1 ? [0.0] : [0.0, 0.0, 0.0],
      ),
    );
  }
}
