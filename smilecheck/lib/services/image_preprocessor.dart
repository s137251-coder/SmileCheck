import 'dart:io';

import 'package:image/image.dart' as img;

class ImagePreprocessor {
  Future<List<List<List<dynamic>>>> preprocess(
    String imagePath, {
    int width = 224,
    int height = 224,
    int channels = 3,
    bool asUint8 = false,
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

    final tensor = List<List<List<dynamic>>>.generate(
      height,
      (y) => List<List<dynamic>>.generate(
        width,
        (x) {
          final pixel = resized.getPixel(x, y);
          final r = (pixel.r / 255.0).clamp(0.0, 1.0).toDouble();
          final g = (pixel.g / 255.0).clamp(0.0, 1.0).toDouble();
          final b = (pixel.b / 255.0).clamp(0.0, 1.0).toDouble();
          if (asUint8) {
            final red = (pixel.r).clamp(0, 255).toInt();
            final green = (pixel.g).clamp(0, 255).toInt();
            final blue = (pixel.b).clamp(0, 255).toInt();
            if (channels == 1) {
              return [((red + green + blue) / 3).round()];
            }
            return [red, green, blue];
          }
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

    final sampleStep = (decoded.width * decoded.height / 200000).ceil().clamp(1, 100);
    var pixelIndex = 0;
    for (final pixel in decoded) {
      if (pixelIndex++ % sampleStep != 0) continue;
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

  List<List<List<dynamic>>> _emptyTensor({
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
