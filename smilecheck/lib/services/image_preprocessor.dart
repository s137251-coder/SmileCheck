import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/image_stats.dart';

/// Everything a single captured frame yields: the resized RGB bytes the model
/// consumes, plus the measurements taken from the full-size frame.
class FramePayload {
  const FramePayload({
    required this.rgb,
    required this.width,
    required this.height,
    required this.stats,
  });

  /// Row-major RGB bytes, `width * height * 3` long.
  final Uint8List rgb;
  final int width;
  final int height;
  final ImageStats stats;
}

/// Request sent to the decode isolate.
class _FrameRequest {
  const _FrameRequest(this.path, this.width, this.height);

  final String path;
  final int width;
  final int height;
}

/// Width the statistics pass runs at. Measuring a downscaled copy keeps a
/// 12-megapixel selfie under the response budget without changing the numbers
/// in any way a user would notice.
const int _statsWidth = 256;

/// Decodes, resizes and measures a frame. Runs in a background isolate so a
/// full-resolution capture never blocks the frame pump.
FramePayload _decodeFrame(_FrameRequest request) {
  final bytes = File(request.path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('The captured image could not be decoded.');
  }

  final resized = img.copyResize(
    decoded,
    width: request.width,
    height: request.height,
    interpolation: img.Interpolation.cubic,
  );

  final rgb = Uint8List(request.width * request.height * 3);
  var offset = 0;
  for (var y = 0; y < request.height; y++) {
    for (var x = 0; x < request.width; x++) {
      final pixel = resized.getPixel(x, y);
      rgb[offset++] = pixel.r.toInt().clamp(0, 255);
      rgb[offset++] = pixel.g.toInt().clamp(0, 255);
      rgb[offset++] = pixel.b.toInt().clamp(0, 255);
    }
  }

  return FramePayload(
    rgb: rgb,
    width: request.width,
    height: request.height,
    stats: _measure(decoded),
  );
}

/// Computes mean luma, luma standard deviation and mean neighbour delta.
ImageStats _measure(img.Image source) {
  final scaled = source.width > _statsWidth
      ? img.copyResize(source, width: _statsWidth)
      : source;

  final width = scaled.width;
  final height = scaled.height;
  if (width < 2 || height < 2) return ImageStats.zero;

  final luma = Float32List(width * height);
  var sum = 0.0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = scaled.getPixel(x, y);
      final value =
          ((pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114)) / 255.0;
      luma[(y * width) + x] = value;
      sum += value;
    }
  }

  final count = width * height;
  final mean = sum / count;

  var variance = 0.0;
  for (var i = 0; i < count; i++) {
    final delta = luma[i] - mean;
    variance += delta * delta;
  }
  final contrast = math.sqrt(variance / count);

  // Mean absolute gradient: the cheap, stable stand-in for focus.
  var gradient = 0.0;
  var gradientCount = 0;
  for (var y = 0; y < height - 1; y++) {
    for (var x = 0; x < width - 1; x++) {
      final here = luma[(y * width) + x];
      gradient += (luma[(y * width) + x + 1] - here).abs();
      gradient += (luma[((y + 1) * width) + x] - here).abs();
      gradientCount += 2;
    }
  }

  return ImageStats(
    brightness: mean.clamp(0.0, 1.0),
    contrast: contrast.clamp(0.0, 1.0),
    sharpness: gradientCount == 0
        ? 0
        : (gradient / gradientCount).clamp(0.0, 1.0).toDouble(),
  );
}

class ImagePreprocessor {
  /// Reads [imagePath] and returns the model input bytes plus frame statistics.
  Future<FramePayload> prepare(
    String imagePath, {
    int width = 224,
    int height = 224,
  }) {
    return compute(_decodeFrame, _FrameRequest(imagePath, width, height));
  }

  /// Measures a frame without preparing model input, for the fallback path.
  Future<ImageStats> measure(String imagePath) async {
    final payload = await prepare(imagePath);
    return payload.stats;
  }

  /// Shapes [payload] into the nested `[height][width][channels]` tensor the
  /// interpreter expects.
  ///
  /// Quantised models take raw 0..255 bytes; float models take 0..1. A
  /// single-channel model gets the luma average rather than a dropped channel.
  List<List<List<num>>> toTensor(
    FramePayload payload, {
    required int channels,
    required bool quantised,
  }) {
    final rgb = payload.rgb;

    return List<List<List<num>>>.generate(
      payload.height,
      (y) => List<List<num>>.generate(
        payload.width,
        (x) {
          final index = ((y * payload.width) + x) * 3;
          final r = rgb[index];
          final g = rgb[index + 1];
          final b = rgb[index + 2];

          if (channels == 1) {
            final grey = ((r * 0.299) + (g * 0.587) + (b * 0.114)).round();
            return quantised ? <num>[grey] : <num>[grey / 255.0];
          }

          return quantised
              ? <num>[r, g, b]
              : <num>[r / 255.0, g / 255.0, b / 255.0];
        },
        growable: false,
      ),
      growable: false,
    );
  }
}
