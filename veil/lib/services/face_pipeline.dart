import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'vision_face.dart';

/// A user-facing reason a photo can't be used. Rejecting bad input up front
/// is the cheapest fix for false matches: most wrong matches come from
/// blurry, dark, tiny or angled faces.
class FaceError implements Exception {
  final String message;
  FaceError(this.message);
  @override
  String toString() => message;
}

/// A normalized face vector tagged with the model that produced it. Vectors
/// from different models are never compared with each other.
class FaceEmbedding {
  final List<double> vector;
  final String embedder;
  FaceEmbedding(this.vector, this.embedder);

  /// Cosine similarity a match must reach, per embedder.
  static double thresholdFor(String embedder) => switch (embedder) {
        FacePipeline.faceModelId => 0.80,
        // Generic image descriptor, not trained on faces: uncalibrated.
        // Debug builds show the best similarity so this can be tuned.
        _ => 0.90,
      };
}

/// Detects one face, checks its quality, and turns it into a normalized
/// embedding entirely on device. The photo itself never leaves the phone.
///
/// Uses the bundled face model when present; otherwise falls back to Apple
/// Vision's built-in image feature print so the app works with no download.
class FacePipeline {
  FacePipeline._();
  static final instance = FacePipeline._();

  static const modelAsset = 'assets/models/mobilefacenet.tflite';
  static const faceModelId = 'mobilefacenet';
  static const fallbackId = 'vision-featureprint';
  static const _inputSize = 112;
  static const _minFacePx = 112;
  static const _maxAngle = 20.0;
  static const _minQuality = 0.2;

  Interpreter? _interpreter;
  bool? _hasModel;

  Future<bool> modelAvailable() async {
    if (_hasModel != null) return _hasModel!;
    try {
      await rootBundle.load(modelAsset);
      return _hasModel = true;
    } catch (_) {
      return _hasModel = false;
    }
  }

  /// Deletes a temporary photo copy (picker/camera output). The Privacy
  /// Policy promises photos are not kept once processed.
  static Future<void> discardPhoto(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<String> activeEmbedder() async =>
      await modelAvailable() ? faceModelId : fallbackId;

  Future<FaceEmbedding> embeddingFromFile(String path) async {
    final faces = await VisionFace.detectFile(path);
    if (faces.isEmpty) {
      throw FaceError('No face found. Use a clear, well-lit photo.');
    }
    if (faces.length > 1) {
      throw FaceError('More than one face. Use a photo of a single person.');
    }
    final face = faces.first;
    if (face.yaw.abs() > _maxAngle || face.roll.abs() > _maxAngle) {
      throw FaceError('Face is turned or tilted. Look straight at the camera.');
    }
    if ((face.quality ?? 1) < _minQuality) {
      throw FaceError('Photo is blurry or poorly framed. Try a sharper one.');
    }

    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) throw FaceError('Could not read that image.');
    final image = img.bakeOrientation(decoded);

    final n = face.box;
    final box = Rect.fromLTWH(n.left * image.width, n.top * image.height,
        n.width * image.width, n.height * image.height);
    if (box.width < _minFacePx || box.height < _minFacePx) {
      throw FaceError('Face is too small or low resolution. Move closer.');
    }

    // 15% margin around the detected box, clamped to the image.
    final margin = box.width * 0.15;
    final x = math.max(0, (box.left - margin).round());
    final y = math.max(0, (box.top - margin).round());
    final w = math.min(image.width - x, (box.width + margin * 2).round());
    final h = math.min(image.height - y, (box.height + margin * 2).round());
    final crop = img.copyResize(
      img.copyCrop(image, x: x, y: y, width: w, height: h),
      width: _inputSize,
      height: _inputSize,
    );

    final brightness = _meanLuma(crop);
    if (brightness < 45) throw FaceError('Too dark. Find better lighting.');
    if (brightness > 215) throw FaceError('Overexposed. Avoid direct glare.');

    if (await modelAvailable()) {
      return FaceEmbedding(_l2normalize(await _runModel(crop)), faceModelId);
    }
    final print = await VisionFace.featurePrint(img.encodePng(crop));
    if (print.isEmpty) throw FaceError('Could not analyze that face.');
    return FaceEmbedding(_l2normalize(print), fallbackId);
  }

  Future<List<double>> _runModel(img.Image crop) async {
    final interp = _interpreter ??= await Interpreter.fromAsset(modelAsset);
    final size = interp.getOutputTensor(0).shape.last;
    final input = Float32List(_inputSize * _inputSize * 3);
    var i = 0;
    for (final p in crop) {
      input[i++] = (p.r - 127.5) / 128;
      input[i++] = (p.g - 127.5) / 128;
      input[i++] = (p.b - 127.5) / 128;
    }
    final output = [List<double>.filled(size, 0)];
    interp.run(input.reshape([1, _inputSize, _inputSize, 3]), output);
    return output.first;
  }

  static double _meanLuma(img.Image im) {
    var sum = 0.0;
    for (final p in im) {
      sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
    return sum / (im.width * im.height);
  }

  static List<double> _l2normalize(List<double> v) {
    final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
    return norm == 0 ? v : v.map((x) => x / norm).toList();
  }

  static double cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return -1;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot; // both are L2-normalized
  }
}
