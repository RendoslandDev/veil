import 'package:flutter/services.dart';

/// One detected face. [box] is normalized (0..1) to the upright image with a
/// top-left origin; angles are in degrees.
class DetectedFace {
  final Rect box;
  final double yaw, roll, pitch;
  final double? leftEye, rightEye, quality;

  DetectedFace.fromMap(Map m)
      : box = Rect.fromLTWH(_d(m['x']), _d(m['y']), _d(m['w']), _d(m['h'])),
        yaw = _d(m['yaw']),
        roll = _d(m['roll']),
        pitch = _d(m['pitch']),
        leftEye = (m['leftEye'] as num?)?.toDouble(),
        rightEye = (m['rightEye'] as num?)?.toDouble(),
        quality = (m['quality'] as num?)?.toDouble();

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
}

/// Bridge to native on-device detection (Apple Vision on iOS). Nothing here
/// touches the network.
class VisionFace {
  static const _channel = MethodChannel('veil/vision');

  static Future<List<DetectedFace>> detectFile(String path) => _call(
      'detectFile', {'path': path});

  static Future<List<DetectedFace>> detectFrame(
          Uint8List bgra, int width, int height, int bytesPerRow) =>
      _call('detectFrame', {
        'bytes': bgra,
        'width': width,
        'height': height,
        'bytesPerRow': bytesPerRow,
      });

  static Future<List<double>> featurePrint(Uint8List png) async {
    final res = await _channel.invokeListMethod<num>('featurePrint', {'png': png});
    return (res ?? const []).map((n) => n.toDouble()).toList();
  }

  static Future<List<DetectedFace>> _call(String method, Map args) async {
    final res = await _channel.invokeListMethod<Map>(method, args);
    return (res ?? const []).map(DetectedFace.fromMap).toList();
  }
}
